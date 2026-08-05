# Secure Wallet Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the current Base-wallet creation failure, replace ambiguous wallet booleans with an explicit recoverable state machine, make create/import transactional, and prove the wallet survives a normal signed APK update.

**Architecture:** Android remains the sole owner of private-key material, Android Keystore authentication, the encrypted envelope, export, and bounded signing. A pure Kotlin classifier converts storage/authentication facts into stable states; `SecureEvmWalletManager` performs authenticated operations and emits those states; Dart maps them into product actions without inferring that a damaged wallet is absent. No generic signer is added.

**Tech Stack:** Kotlin 17, Android Keystore, `AtomicFile`, Web3j, Flutter MethodChannel, Dart/Flutter, JUnit 4, Flutter unit/widget tests, ADB device acceptance.

---

## Scope and invariants

- Preserve `plawie_base_evm_envelope_v1` and `base_evm_wallet_v1.json`; changing either would strand existing wallets.
- Keep the envelope under `noBackupFilesDir`. Same-package, same-signing-key APK updates preserve it; uninstall and clear-data delete it.
- Never expose a private key, ciphertext, signature, signed transaction, auth token, or secret header to Dart or logs.
- Never turn a damaged envelope into an ordinary Create flow. Recovery is explicit and destructive only after warning and device authentication where authentication remains possible.
- Keep the current bounded signers. This slice does not add arbitrary calldata, typed-data, digest, or personal-message signing.
- Do not change production wallet code until Task 1 records the actual device error and maps it to a failing regression test.

## File map

**Create**

- `android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletState.kt`
- `android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletTransaction.kt`
- `android/app/src/test/kotlin/com/openclaw/plawie/SecureEvmWalletStateTest.kt`
- `android/app/src/test/kotlin/com/openclaw/plawie/SecureEvmWalletTransactionTest.kt`
- `test/base_wallet_state_test.dart`
- `test/base_wallet_recovery_view_model_test.dart`
- `docs/BASE_WALLET_SECURITY_AND_RECOVERY.md`

**Modify**

- `android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletManager.kt`
- `android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt`
- `lib/services/native_bridge.dart`
- `lib/services/base_service.dart`
- `lib/screens/base_screen.dart`
- `lib/screens/management/skills/agent_base_page.dart`
- `test/base_transfer_approval_test.dart`

## Task 1: Reproduce and classify the device failure

**Purpose:** Establish evidence before selecting a fix. The current source permits an envelope file to exist while `status()` reports `exists: false`; that is a candidate, not a confirmed cause.

- [ ] **Step 1: Confirm the connected package and capture a clean log window**

Run:

```powershell
adb devices -l
adb shell pm path com.openclaw.plawie
adb logcat -c
```

Expected: exactly one authorized device and at least one package path. If no device is listed, stop this task without changing wallet code.

- [ ] **Step 2: Reproduce once from the Base page**

Ask the user to tap `Create wallet` once. Do not relaunch, clear data, uninstall, or tap repeatedly. Then run:

```powershell
adb logcat -d -v threadtime SecureEvmWallet:V flutter:I AndroidRuntime:E *:S
adb shell run-as com.openclaw.plawie ls -la no_backup
adb shell run-as com.openclaw.plawie stat -c '%n %s bytes' no_backup/base_evm_wallet_v1.json
```

Expected: a stable Android/Flutter error code plus envelope presence and size. A missing `stat` target is valid evidence for the absent case.

- [ ] **Step 3: Record only redacted facts**

Add a dated “Observed failure” section to `docs/BASE_WALLET_SECURITY_AND_RECOVERY.md` containing Android version, app version, operation, returned error code, envelope present/absent, Keystore state reported by the new diagnostic probe when available, and whether the prompt appeared. Do not paste cryptographic material or a full logcat dump.

- [ ] **Step 4: Convert the observed case into the first failing test**

Choose the matching facts in Task 2’s classifier test. Run:

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest --tests com.openclaw.plawie.SecureEvmWalletStateTest
```

Expected before implementation: compilation failure because the classifier does not exist, followed by a specific assertion failure once its shell exists.

- [ ] **Step 5: Commit the evidence and failing test separately**

```powershell
git add docs/BASE_WALLET_SECURITY_AND_RECOVERY.md android/app/src/test/kotlin/com/openclaw/plawie/SecureEvmWalletStateTest.kt
git commit -m "test: capture Base wallet creation failure"
```

## Task 2: Introduce the native wallet-state contract

**Files:** Create `SecureEvmWalletState.kt`; modify `SecureEvmWalletManager.kt`.

- [ ] **Step 1: Write table-driven classifier tests**

Cover `absent`, `healthy`, `authenticationUnavailable`, `envelopeCorrupt`, `keystoreKeyMissing`, `keystoreKeyInvalidated`, `orphanedKeystoreAlias`, and `operationBusy`. The pure facts and precedence are:

```kotlin
internal data class WalletStorageFacts(
    val envelopePresent: Boolean,
    val envelopeParseable: Boolean,
    val keyAliasPresent: Boolean,
    val keyInvalidated: Boolean,
    val authenticationAvailable: Boolean,
    val operationActive: Boolean,
)

internal enum class SecureEvmWalletState(val wireName: String) {
    ABSENT("absent"),
    HEALTHY("healthy"),
    AUTHENTICATION_UNAVAILABLE("authenticationUnavailable"),
    ENVELOPE_CORRUPT("envelopeCorrupt"),
    KEY_MISSING("keystoreKeyMissing"),
    KEY_INVALIDATED("keystoreKeyInvalidated"),
    ORPHANED_ALIAS("orphanedKeystoreAlias"),
    OPERATION_BUSY("operationBusy"),
}
```

Assert precedence: busy first; corrupt envelope before key checks; parsed envelope plus missing/invalid key before auth; alias without envelope is orphaned; only parsed envelope plus usable key is healthy.

- [ ] **Step 2: Run the focused test and see it fail**

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest --tests com.openclaw.plawie.SecureEvmWalletStateTest
```

Expected: unresolved `WalletStorageFacts`/`SecureEvmWalletStateClassifier`.

- [ ] **Step 3: Implement the pure classifier**

Create `SecureEvmWalletState.kt` with:

```kotlin
internal object SecureEvmWalletStateClassifier {
    fun classify(facts: WalletStorageFacts): SecureEvmWalletState = when {
        facts.operationActive -> SecureEvmWalletState.OPERATION_BUSY
        facts.envelopePresent && !facts.envelopeParseable -> SecureEvmWalletState.ENVELOPE_CORRUPT
        facts.envelopePresent && !facts.keyAliasPresent -> SecureEvmWalletState.KEY_MISSING
        facts.envelopePresent && facts.keyInvalidated -> SecureEvmWalletState.KEY_INVALIDATED
        !facts.envelopePresent && facts.keyAliasPresent -> SecureEvmWalletState.ORPHANED_ALIAS
        !facts.authenticationAvailable -> SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE
        facts.envelopePresent -> SecureEvmWalletState.HEALTHY
        else -> SecureEvmWalletState.ABSENT
    }
}
```

- [ ] **Step 4: Make `status()` emit the state and stable error code**

Probe envelope parseability, alias presence, authentication availability, operation state, and key invalidation without decrypting or prompting. Return existing compatibility fields plus:

```kotlin
"state" to state.wireName,
"errorCode" to state.errorCode,
"canCreate" to (state == SecureEvmWalletState.ABSENT ||
    state == SecureEvmWalletState.ORPHANED_ALIAS),
"canRestore" to (state != SecureEvmWalletState.OPERATION_BUSY),
"requiresDestructiveRecovery" to setOf(
    SecureEvmWalletState.ENVELOPE_CORRUPT,
    SecureEvmWalletState.KEY_MISSING,
    SecureEvmWalletState.KEY_INVALIDATED,
).contains(state),
```

Use `android.util.Log.i(TAG, ...)` for one redacted line containing only operation, state, envelope presence, alias presence, security level, and stable error code.

- [ ] **Step 5: Run tests and static checks**

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest --tests com.openclaw.plawie.SecureEvmWalletStateTest
./gradlew.bat :app:compileDebugKotlin
```

Expected: all classifier tests pass and Kotlin compilation succeeds.

- [ ] **Step 6: Commit the native state contract**

```powershell
git add android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletState.kt android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletManager.kt android/app/src/test/kotlin/com/openclaw/plawie/SecureEvmWalletStateTest.kt
git commit -m "feat: expose explicit secure wallet states"
```

## Task 3: Make create and import transactional

**Files:** Modify `SecureEvmWalletManager.kt`; create `SecureEvmWalletTransaction.kt` and `SecureEvmWalletTransactionTest.kt`.

- [ ] **Step 1: Add failing rollback and collision tests**

Introduce an internal `WalletCommitStore` interface around alias/envelope operations so JVM tests can model failures without Android Keystore:

```kotlin
internal interface WalletCommitStore {
    fun aliasExists(): Boolean
    fun deleteAlias()
    fun envelopeExists(): Boolean
    fun writeEnvelope(envelope: WalletEnvelopeRecord)
    fun readEnvelope(): WalletEnvelopeRecord
    fun deletePartialEnvelope()
}
```

Test: no artifact on auth cancellation; newly created alias removed after write failure; pre-existing alias never removed by rollback; read-back mismatch fails; corrupt/missing-key state rejects create; orphaned alias is removed only after explicit recovery.

- [ ] **Step 2: Run the focused tests and confirm failure**

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest --tests "com.openclaw.plawie.SecureEvmWallet*Test"
```

Expected: new transaction tests fail because commit/rollback boundaries are not represented.

- [ ] **Step 3: Guard create/import by explicit state**

Replace raw `envelopeFile.baseFile.exists()` checks with `currentState()`. Permit create/import only from `ABSENT`. Return the state’s stable code for damaged/busy/auth-unavailable states. `ORPHANED_ALIAS` requires the explicit recovery method in Task 5 before create.

- [ ] **Step 4: Track artifacts created by the current attempt**

Inside `encryptAndStore`, track `aliasCreatedByAttempt` and `envelopeCommitted`. On failure before a valid commit, call `failWrite`/remove partial atomic artifacts and delete only an alias created by that attempt. Zero the private-key byte array in every callback and exception branch.

- [ ] **Step 5: Verify the committed envelope before reporting success**

After `finishWrite`, reopen and parse the envelope, compare version/address/IV/ciphertext to the committed record, and rederive the address from the in-memory key before zeroing it. Then obtain an authenticated decrypt operation for the committed envelope and verify the decrypted key derives the same address. If the second prompt is cancelled, retain the valid envelope and return `WALLET_CREATED_VERIFICATION_PENDING`; `status()` must report `healthy`, and the UI must explain that creation succeeded but verification was deferred.

- [ ] **Step 6: Serialize asynchronous completions exactly once**

Use one per-operation `AtomicBoolean completed`; every prompt callback enters a common `finishSuccess` or `finishError`, zeros memory, resets `operationActive`, and invokes `MethodChannel.Result` at most once.

- [ ] **Step 7: Run native tests**

```powershell
cd android
./gradlew.bat :app:testDebugUnitTest
./gradlew.bat :app:lintDebug
```

Expected: all JVM tests pass and lint has no new errors.

- [ ] **Step 8: Commit transactional creation**

```powershell
git add android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletManager.kt android/app/src/test/kotlin/com/openclaw/plawie
git commit -m "fix: make secure wallet creation transactional"
```

## Task 4: Map native states into Dart without inference

**Files:** Modify `native_bridge.dart` and `base_service.dart`; create `base_wallet_state_test.dart`.

- [ ] **Step 1: Write failing mapping tests**

Define fixtures for each native `state`; assert unknown wire values map to `SecureWalletState.unavailable`, not `absent`; assert legacy secure-storage presence maps to `legacyMigrationRequired` only when native state is absent.

- [ ] **Step 2: Add immutable Dart models**

Implement:

```dart
enum SecureWalletState {
  absent,
  healthy,
  legacyMigrationRequired,
  authenticationUnavailable,
  envelopeCorrupt,
  keystoreKeyMissing,
  keystoreKeyInvalidated,
  orphanedKeystoreAlias,
  operationBusy,
  unavailable,
}

class SecureWalletStatus {
  const SecureWalletStatus({
    required this.state,
    required this.address,
    required this.securityLevel,
    required this.authenticationMode,
    required this.errorCode,
  });
  // fromNative performs the exhaustive wire mapping.
}
```

- [ ] **Step 3: Refactor `BaseService.initialize()` and getters**

Store one `SecureWalletStatus`. Preserve `isConnected`, `address`, `legacyMigrationRequired`, and existing events as compatibility getters derived from that status. Do not catch a native state error and substitute `exists: false`.

- [ ] **Step 4: Preserve error codes across the MethodChannel**

Map `PlatformException.code` into a typed `SecureWalletException`; UI copy chooses the next safe action from state/code. Logs include code/state only.

- [ ] **Step 5: Run focused Flutter tests**

```powershell
flutter test test/base_wallet_state_test.dart test/base_transfer_approval_test.dart
dart analyze lib/services/native_bridge.dart lib/services/base_service.dart
```

Expected: tests pass and no new analyzer findings.

- [ ] **Step 6: Commit Dart state mapping**

```powershell
git add lib/services/native_bridge.dart lib/services/base_service.dart test/base_wallet_state_test.dart test/base_transfer_approval_test.dart
git commit -m "feat: map secure wallet recovery states in Dart"
```

## Task 5: Add safe recovery actions and accurate UI

**Files:** Modify Android manager/MainActivity, NativeBridge, BaseService, Base screen, and agent Base page; create `base_wallet_recovery_view_model_test.dart`.

- [ ] **Step 1: Write failing action-availability tests**

Extract a pure `BaseWalletRecoveryViewModel.fromStatus`. Assert:

- absent: Create and Import;
- healthy: Backup and Remove;
- legacy migration: Migrate and Import disabled;
- auth unavailable: device-lock guidance only;
- corrupt/missing/invalidated: Restore backup and authenticated destructive removal, never ordinary Create;
- orphaned alias: Remove orphaned protection record, then refresh;
- busy: actions disabled.

- [ ] **Step 2: Add bounded recovery MethodChannel methods**

Register `recoverOrphanedSecureEvmAlias` and `removeDamagedSecureEvmWallet`. The first succeeds only when state is exactly `orphanedKeystoreAlias`. The second accepts only corrupt/missing/invalidated states, shows an Android-owned destructive warning, requires device authentication when the alias can still authenticate, then removes the known envelope/alias. It does not reveal key data.

- [ ] **Step 3: Render state-specific Base-page cards**

Replace the generic disconnected card with explicit status, consequence, and safe action. Include permanent copy: “Signed app updates preserve this wallet. Clearing app data or uninstalling Plawie removes it. Export a backup before funding it.”

- [ ] **Step 4: Keep agent capabilities read-only**

Update the agent Base page/status capability to report state and recovery guidance, but do not expose recovery, backup, import, delete, or create as agent-callable commands.

- [ ] **Step 5: Run tests and analyzer**

```powershell
flutter test test/base_wallet_recovery_view_model_test.dart test/base_wallet_state_test.dart
dart analyze lib/screens/base_screen.dart lib/screens/management/skills/agent_base_page.dart lib/services/base_service.dart
cd android
./gradlew.bat :app:testDebugUnitTest
```

Expected: action matrix tests pass; Android tests pass; no new analyzer findings.

- [ ] **Step 6: Commit recovery UI**

```powershell
git add android/app/src/main/kotlin/com/openclaw/plawie lib/services/native_bridge.dart lib/services/base_service.dart lib/screens/base_screen.dart lib/screens/management/skills/agent_base_page.dart test/base_wallet_recovery_view_model_test.dart docs/BASE_WALLET_SECURITY_AND_RECOVERY.md
git commit -m "feat: add explicit Base wallet recovery flows"
```

## Task 6: Prove persistence and bounded signing on a device

- [ ] **Step 1: Build and install without clearing data**

```powershell
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Expected: `Success`. Never run `pm clear` or uninstall during this proof.

- [ ] **Step 2: Create/import and record only the public address**

Create or import through the Base page, authenticate, close and relaunch the app, and verify the same public address appears.

- [ ] **Step 3: Install the next same-signed build as an update**

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am force-stop com.openclaw.plawie
adb shell monkey -p com.openclaw.plawie -c android.intent.category.LAUNCHER 1
```

Expected: same public address and `healthy`; no migration/recreation prompt.

- [ ] **Step 4: Exercise bounded operations**

Verify backup requires authentication and remains Android-owned; cancel one Base transfer prompt and confirm no broadcast; verify generic signing remains unavailable in status.

- [ ] **Step 5: Run the complete slice verification**

```powershell
flutter test test/base_wallet_state_test.dart test/base_wallet_recovery_view_model_test.dart test/base_transfer_approval_test.dart
cd android
./gradlew.bat :app:testDebugUnitTest :app:lintDebug
cd ..
flutter analyze
git diff --check
```

Expected: all tests pass, lint/analyze add no errors, and `git diff --check` is silent.

- [ ] **Step 6: Record redacted acceptance evidence and commit**

Update `docs/BASE_WALLET_SECURITY_AND_RECOVERY.md` with app version, Android version, same public address before/after update, tested states, and outcome. Then:

```powershell
git add docs/BASE_WALLET_SECURITY_AND_RECOVERY.md
git commit -m "docs: record secure wallet persistence proof"
```

## Completion gate

- [ ] The original device failure is reproduced and represented by a regression test.
- [ ] Native and Dart state names match exactly.
- [ ] Damaged wallet states never render ordinary Create.
- [ ] A failed create leaves no partial envelope or newly orphaned alias.
- [ ] Existing envelope/alias pairs are never removed by generic rollback.
- [ ] The same wallet address survives restart and same-signed APK update.
- [ ] Clear-data/uninstall is absent from update verification.
- [ ] Logs and tests contain no private key, ciphertext, signature, or secret.
- [ ] Every significant implementation round is committed; generated APKs and build reports are not committed.

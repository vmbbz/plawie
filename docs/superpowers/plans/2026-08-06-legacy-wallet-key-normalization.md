# Legacy Base Wallet Key Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Safely migrate historically valid variable-width Web3dart private-key encodings into the authenticated Android Keystore envelope without changing the wallet address.

**Architecture:** A pure Dart normalizer converts only historically possible serialized scalars into canonical 32-byte keys and rejects every wider or invalid representation. `BaseService` uses the normalizer during initialization and migration, verifies address continuity before and after native import, and deletes the FlutterSecureStorage record only after Android reports the same verified identity.

**Tech Stack:** Dart 3, Flutter, Web3dart 2.7.3, FlutterSecureStorage, Android MethodChannel wallet bridge, Flutter tests, ADB device acceptance.

---

## File map

- Create `lib/services/legacy_evm_key_normalizer.dart`: pure historical-format validation and canonical 32-byte normalization.
- Create `test/legacy_evm_key_normalizer_test.dart`: behavioral compatibility and rejection tests using real Web3dart address derivation.
- Modify `lib/services/base_service.dart`: fail-closed legacy detection, address-continuity validation, and transactional deletion ordering.
- Create `test/base_wallet_legacy_migration_contract_test.dart`: source contract for migration ordering and fail-closed initialization.
- Modify `docs/BASE_WALLET_SECURITY_AND_RECOVERY.md`: record the historical serialization incident and compatibility boundary.

### Task 1: Pure legacy scalar normalization

**Files:**
- Create: `lib/services/legacy_evm_key_normalizer.dart`
- Create: `test/legacy_evm_key_normalizer_test.dart`

- [ ] **Step 1: Write the failing behavior tests**

Create tests that exercise real output bytes and address derivation:

```dart
import 'package:clawa/services/legacy_evm_key_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  const canonical =
      '8000000000000000000000000000000000000000000000000000000000000001';

  test('removes the historical ASN.1 zero sign byte', () {
    final normalized = LegacyEvmKeyNormalizer.normalize('00$canonical');
    expect(normalized, hasLength(32));
    expect(
      EthPrivateKey(normalized).address.hexEip55,
      EthPrivateKey.fromHex('00$canonical').address.hexEip55,
    );
  });

  test('left pads short historical scalar bytes', () {
    final normalized = LegacyEvmKeyNormalizer.normalize('01');
    expect(normalized, hasLength(32));
    expect(normalized.take(31), everyElement(0));
    expect(normalized.last, 1);
  });

  test('retains a canonical 32-byte scalar', () {
    expect(
      LegacyEvmKeyNormalizer.normalize(canonical),
      orderedEquals(EthPrivateKey.fromHex(canonical).privateKey),
    );
  });

  test('rejects formats outside the historical contract', () {
    final invalid = <String>[
      '',
      '0',
      'xyz0',
      '01$canonical',
      '0000$canonical',
      '00',
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    ];
    for (final value in invalid) {
      expect(
        () => LegacyEvmKeyNormalizer.normalize(value),
        throwsFormatException,
        reason: 'value length ${value.length}',
      );
    }
  });
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```powershell
flutter test test/legacy_evm_key_normalizer_test.dart --no-pub
```

Expected: FAIL because `legacy_evm_key_normalizer.dart` and
`LegacyEvmKeyNormalizer` do not exist.

- [ ] **Step 3: Implement the strict normalizer**

Create the pure component with this public contract:

```dart
import 'dart:typed_data';

import 'package:web3dart/crypto.dart';

final class LegacyEvmKeyNormalizer {
  static final BigInt _curveOrder = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  static Uint8List normalize(String serialized) {
    var clean = serialized;
    if (clean.startsWith('0x')) clean = clean.substring(2);
    if (clean.isEmpty || clean.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw const FormatException('Legacy wallet key encoding is invalid.');
    }
    if (clean.length == 66) {
      if (!clean.startsWith('00')) {
        throw const FormatException('Legacy wallet key encoding is invalid.');
      }
      clean = clean.substring(2);
    }
    if (clean.length > 64) {
      throw const FormatException('Legacy wallet key encoding is invalid.');
    }
    clean = clean.padLeft(64, '0');
    final scalar = BigInt.parse(clean, radix: 16);
    if (scalar <= BigInt.zero || scalar >= _curveOrder) {
      throw const FormatException('Legacy wallet key scalar is invalid.');
    }
    return Uint8List.fromList(hexToBytes(clean));
  }
}
```

Do not log `serialized`, `clean`, bytes, or derived signatures.

- [ ] **Step 4: Run the focused tests and confirm GREEN**

Run:

```powershell
flutter test test/legacy_evm_key_normalizer_test.dart --no-pub
```

Expected: all normalizer tests pass.

- [ ] **Step 5: Commit the compatibility component**

```powershell
git add lib/services/legacy_evm_key_normalizer.dart test/legacy_evm_key_normalizer_test.dart
git commit -m "fix: normalize historical Base wallet keys"
```

### Task 2: Transactional legacy migration and identity continuity

**Files:**
- Modify: `lib/services/base_service.dart:148-175`
- Modify: `lib/services/base_service.dart:177-189`
- Modify: `lib/services/base_service.dart:238-260`
- Create: `test/base_wallet_legacy_migration_contract_test.dart`

- [ ] **Step 1: Write the failing migration contract test**

The test must read `base_service.dart` and assert all of these structural
invariants:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy migration normalizes and validates identity before deletion', () {
    final source = File('lib/services/base_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(source, contains('LegacyEvmKeyNormalizer.normalize(stored)'));
    expect(source, contains('_legacyMigrationRequired = true'));
    expect(source, contains('Legacy wallet identity changed during normalization.'));
    expect(source, contains('Android imported a different wallet identity.'));

    final migration = source.substring(source.indexOf('Future<void> migrateLegacyWallet()'));
    final importIndex = migration.indexOf('NativeBridge.importSecureEvmWallet');
    final nativeIdentityIndex = migration.indexOf('Android imported a different wallet identity.');
    final deleteIndex = migration.indexOf("_secureStorage.delete(key: 'base_private_key')");
    expect(importIndex, greaterThanOrEqualTo(0));
    expect(nativeIdentityIndex, greaterThan(importIndex));
    expect(deleteIndex, greaterThan(nativeIdentityIndex));
  });
}
```

- [ ] **Step 2: Run the contract test and confirm RED**

Run:

```powershell
flutter test test/base_wallet_legacy_migration_contract_test.dart --no-pub
```

Expected: FAIL because normalization and continuity checks are absent and the
legacy record is currently deleted before native status validation.

- [ ] **Step 3: Make initialization fail closed**

Import `legacy_evm_key_normalizer.dart`. When a non-empty legacy record exists,
set `_legacyMigrationRequired = true` before parsing it. Normalize into a local
`Uint8List`, derive `_address` from `EthPrivateKey(normalized)`, keep
`_isConnected = false`, and zero the bytes in `finally`. If normalization fails,
retain `_legacyMigrationRequired = true` so Create Wallet cannot replace the
record.

- [ ] **Step 4: Add non-mutating native status validation**

Extract a helper which validates `exists == true`, parses the reported address
to EIP-55, and returns that address without changing service state:

```dart
String _validatedNativeWalletAddress(Map<String, dynamic> status) {
  final address = status['address']?.toString().trim() ?? '';
  if (status['exists'] != true || address.isEmpty) {
    throw StateError('Android reported an invalid secure wallet status.');
  }
  return EthereumAddress.fromHex(address).hexEip55;
}
```

Use it inside `_applyNativeWalletStatus()` to avoid duplicate parsing.

- [ ] **Step 5: Make migration preserve identity and deletion ordering**

Normalize the stored value, derive its address, compare it case-insensitively
with the initialized `_address`, invoke Android with exactly 32 bytes, validate
the returned native address against the normalized address, apply native
status, and only then delete `base_private_key`. Use these stable errors:

```dart
throw StateError('Legacy wallet identity changed during normalization.');
throw StateError('Android imported a different wallet identity.');
```

Retain the existing `finally` byte clearing. Do not delete the legacy record in
any error or authentication-cancellation path.

- [ ] **Step 6: Run focused tests and static analysis**

Run:

```powershell
flutter test test/legacy_evm_key_normalizer_test.dart test/base_wallet_legacy_migration_contract_test.dart --no-pub
flutter analyze lib/services/legacy_evm_key_normalizer.dart lib/services/base_service.dart test/legacy_evm_key_normalizer_test.dart test/base_wallet_legacy_migration_contract_test.dart --no-pub
```

Expected: all focused tests pass and analysis reports no issues.

- [ ] **Step 7: Commit the migration transaction**

```powershell
git add lib/services/base_service.dart test/base_wallet_legacy_migration_contract_test.dart
git commit -m "fix: preserve identity during wallet migration"
```

### Task 3: Document and verify the compatibility repair

**Files:**
- Modify: `docs/BASE_WALLET_SECURITY_AND_RECOVERY.md`

- [ ] **Step 1: Record the incident without key material**

Add a dated section documenting: valid address derivation, Dart-side exact-64
rejection, historical signed-minimal Web3dart encoding, strict normalization,
address continuity, and deletion-after-native-confirmation. Do not include a
private key, encrypted value, signature, or full secure-storage dump.

- [ ] **Step 2: Run the full project verification**

Run:

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build apk --debug
```

Expected: all Flutter tests pass, analysis reports no issues, and
`build/app/outputs/flutter-apk/app-debug.apk` is produced. The Gradle embedded
Node gate must pass during APK assembly.

- [ ] **Step 3: Commit the incident documentation**

```powershell
git add docs/BASE_WALLET_SECURITY_AND_RECOVERY.md
git commit -m "docs: record legacy wallet migration compatibility"
```

### Task 4: In-place device acceptance

**Files:**
- Build artifact only: `build/app/outputs/flutter-apk/app-debug.apk`
- Device state: existing app data and wallet records

- [ ] **Step 1: Install once without clearing data**

```powershell
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb shell am force-stop com.openclaw.plawie
adb shell monkey -p com.openclaw.plawie -c android.intent.category.LAUNCHER 1
```

Expected: streamed install succeeds. Do not uninstall or run `pm clear`.

- [ ] **Step 2: Open Base and initiate migration once**

Use UIAutomator to locate the Base page and `Secure existing wallet`. Tap the
card, then `Secure wallet` once. Stop automation while Android's authentication
prompt is visible and ask the user to approve it physically.

- [ ] **Step 3: Verify storage and identity using redacted metadata**

After authentication, verify:

```powershell
adb shell run-as com.openclaw.plawie stat -c '%n bytes=%s' no_backup/base_evm_wallet_v1.json
adb shell uiautomator dump /sdcard/plawie-wallet-result.xml
adb logcat -d -v threadtime SecureEvmWallet:V flutter:I AndroidRuntime:E '*:S'
```

Expected: the envelope exists, the Base page shows `0xab29...B434` without the
migration card, and logs contain no private key, invalid-key exception, or
Android crash. Inspect only metadata and redacted UI labels; never print secure
storage content.

- [ ] **Step 4: Verify native Gateway remains healthy**

Confirm `com.openclaw.plawie:native_node_smoke` is running, no PRoot process is
running, and the persisted node snapshot still contains 82 commands. Do not
restart the app again.

- [ ] **Step 5: Final repository check**

```powershell
git restore -- android/build/reports/problems/problems-report.html
git diff --check
git status --short
git log -8 --oneline
```

Expected: clean worktree, no APK/runtime/temp files tracked, and each
significant round committed.

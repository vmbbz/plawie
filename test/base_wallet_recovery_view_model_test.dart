import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/base_wallet_recovery_view_model.dart';
import 'package:clawa/services/native_bridge.dart';

void main() {
  test('absent offers only create and import', () {
    final view = viewFor('absent');
    expect(view.canCreate, isTrue);
    expect(view.canImport, isTrue);
    expect(view.canMigrate, isFalse);
    expect(view.canBackup, isFalse);
    expect(view.canRemove, isFalse);
  });

  test('healthy offers backup and ordinary authenticated removal', () {
    final view = viewFor(
      'healthy',
      address: '0x1111111111111111111111111111111111111111',
    );
    expect(view.canBackup, isTrue);
    expect(view.canRemove, isTrue);
    expect(view.canCreate, isFalse);
    expect(view.canImport, isFalse);
  });

  test('legacy wallet offers migration but blocks replacement', () {
    final absent = SecureWalletStatus.fromNative(
      const <String, dynamic>{'state': 'absent'},
    );
    final status = absent.withLegacyWalletAddress(
      '0x2222222222222222222222222222222222222222',
    );
    final view = BaseWalletRecoveryViewModel.fromStatus(status);

    expect(view.canMigrate, isTrue);
    expect(view.canImport, isFalse);
    expect(view.canCreate, isFalse);
  });

  test('authentication unavailable gives guidance and no mutation action', () {
    final view = viewFor('authenticationUnavailable');
    expect(view.actionsEnabled, isFalse);
    expect(view.canCreate, isFalse);
    expect(view.canRemoveDamaged, isFalse);
    expect(view.guidance.toLowerCase(), contains('device lock'));
  });

  test('damaged wallet offers restore and bounded destructive removal only',
      () {
    for (final state in <String>[
      'envelopeCorrupt',
      'keystoreKeyMissing',
      'keystoreKeyInvalidated',
    ]) {
      final view = viewFor(state);
      expect(view.canRestoreBackup, isTrue, reason: state);
      expect(view.canRemoveDamaged, isTrue, reason: state);
      expect(view.canCreate, isFalse, reason: state);
      expect(view.canImport, isFalse, reason: state);
    }
  });

  test('orphaned alias exposes only orphan cleanup', () {
    final view = viewFor('orphanedKeystoreAlias');
    expect(view.canRemoveOrphanedAlias, isTrue);
    expect(view.canCreate, isFalse);
    expect(view.canImport, isFalse);
    expect(view.canRemoveDamaged, isFalse);
  });

  test('busy and unavailable states disable actions', () {
    for (final state in <String>['operationBusy', 'futureState']) {
      final view = viewFor(state);
      expect(view.actionsEnabled, isFalse, reason: state);
      expect(view.hasMutationAction, isFalse, reason: state);
    }
  });
}

BaseWalletRecoveryViewModel viewFor(String state, {String address = ''}) {
  return BaseWalletRecoveryViewModel.fromStatus(
    SecureWalletStatus.fromNative(<String, dynamic>{
      'state': state,
      'address': address,
      'errorCode': '',
    }),
  );
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.openclaw.plawie/native');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('native state wire names map exhaustively', () {
    const cases = <String, SecureWalletState>{
      'absent': SecureWalletState.absent,
      'healthy': SecureWalletState.healthy,
      'authenticationUnavailable': SecureWalletState.authenticationUnavailable,
      'envelopeCorrupt': SecureWalletState.envelopeCorrupt,
      'keystoreKeyMissing': SecureWalletState.keystoreKeyMissing,
      'keystoreKeyInvalidated': SecureWalletState.keystoreKeyInvalidated,
      'orphanedKeystoreAlias': SecureWalletState.orphanedKeystoreAlias,
      'operationBusy': SecureWalletState.operationBusy,
    };

    for (final entry in cases.entries) {
      final status = SecureWalletStatus.fromNative(<String, dynamic>{
        'state': entry.key,
        'address': entry.value == SecureWalletState.healthy
            ? '0x1111111111111111111111111111111111111111'
            : '',
        'securityLevel': 'Trusted Environment',
        'authenticationMode': 'device credential',
        'errorCode': '',
      });
      expect(status.state, entry.value, reason: entry.key);
    }
  });

  test('unknown or missing native state maps to unavailable, never absent', () {
    expect(
      SecureWalletStatus.fromNative(
        const <String, dynamic>{'state': 'futureState'},
      ).state,
      SecureWalletState.unavailable,
    );
    expect(
      SecureWalletStatus.fromNative(const <String, dynamic>{}).state,
      SecureWalletState.unavailable,
    );
  });

  test('legacy migration state is derived only from native absent', () {
    const legacyAddress = '0x2222222222222222222222222222222222222222';
    final absent = SecureWalletStatus.fromNative(
      const <String, dynamic>{'state': 'absent'},
    );
    final corrupt = SecureWalletStatus.fromNative(
      const <String, dynamic>{
        'state': 'envelopeCorrupt',
        'errorCode': 'WALLET_ENVELOPE_CORRUPT',
      },
    );

    final legacy = absent.withLegacyWalletAddress(legacyAddress);
    expect(legacy.state, SecureWalletState.legacyMigrationRequired);
    expect(legacy.address, legacyAddress);
    expect(
      corrupt.withLegacyWalletAddress(legacyAddress).state,
      SecureWalletState.envelopeCorrupt,
    );
  });

  test('verification-pending receipt is preserved by the typed model', () {
    final status = SecureWalletStatus.fromNative(const <String, dynamic>{
      'state': 'healthy',
      'address': '0x3333333333333333333333333333333333333333',
      'verificationPending': true,
      'verificationCode': 'WALLET_CREATED_VERIFICATION_PENDING',
    });

    expect(status.verificationPending, isTrue);
    expect(status.verificationCode, 'WALLET_CREATED_VERIFICATION_PENDING');
    expect(status.isConnected, isTrue);
  });

  test('MethodChannel wallet errors retain their stable native code', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getSecureEvmWalletStatus') {
        throw PlatformException(
          code: 'WALLET_KEY_INVALIDATED',
          message: 'Restore from backup.',
        );
      }
      return null;
    });

    await expectLater(
      NativeBridge.getSecureEvmWalletStatus(),
      throwsA(
        isA<SecureWalletException>()
            .having((error) => error.code, 'code', 'WALLET_KEY_INVALIDATED')
            .having(
                (error) => error.message, 'message', 'Restore from backup.'),
      ),
    );
  });
}

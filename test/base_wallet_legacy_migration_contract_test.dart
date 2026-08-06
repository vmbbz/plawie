import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy migration normalizes and validates identity before deletion',
      () {
    final source = File('lib/services/base_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(source, contains('LegacyEvmKeyNormalizer.normalize(stored)'));
    expect(
      source,
      contains('nativeStatus.state == SecureWalletState.absent'),
    );
    expect(source, contains('nativeStatus.withLegacyWalletAddress('));
    expect(
      source,
      contains('Legacy wallet identity changed during normalization.'),
    );
    expect(
      source,
      contains('Android imported a different wallet identity.'),
    );

    final migration = source.substring(
      source.indexOf('Future<void> migrateLegacyWallet()'),
    );
    final importIndex = migration.indexOf(
      'NativeBridge.importSecureEvmWallet',
    );
    final nativeIdentityIndex = migration.indexOf(
      'Android imported a different wallet identity.',
    );
    final deleteIndex = migration.indexOf(
      "_secureStorage.delete(key: 'base_private_key')",
    );
    expect(importIndex, greaterThanOrEqualTo(0));
    expect(nativeIdentityIndex, greaterThan(importIndex));
    expect(deleteIndex, greaterThan(nativeIdentityIndex));
  });
}

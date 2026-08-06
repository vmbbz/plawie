import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet uses biometric API masks separately from Keystore masks', () {
    final source = File(
      'android/app/src/main/kotlin/com/openclaw/plawie/'
      'SecureEvmWalletManager.kt',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      source,
      contains(
        'builder.setAllowedAuthenticators('
        'WalletAuthenticatorPolicy.biometricApiMask)',
      ),
    );
    expect(
      source,
      contains(
        'manager.canAuthenticate(WalletAuthenticatorPolicy.biometricApiMask)',
      ),
    );
    expect(
      source,
      contains('WalletAuthenticatorPolicy.keyStoreMask'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'BiometricManager\.Authenticators\.BIOMETRIC_STRONG\s+or\s+'
          r'BiometricManager\.Authenticators\.DEVICE_CREDENTIAL',
        ),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r'KeyProperties\.AUTH_BIOMETRIC_STRONG\s+or\s+'
          r'KeyProperties\.AUTH_DEVICE_CREDENTIAL',
        ),
      ),
    );
    expect(source, contains('catch (error: SecurityException)'));
  });
}

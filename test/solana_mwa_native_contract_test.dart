import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  test('Android uses the exact official MWA 2.1 dependency and one bridge', () {
    final gradle = read('android/app/build.gradle.kts');
    final rootGradle = read('android/build.gradle.kts');
    final activity = read(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    );

    expect(
      gradle,
      contains(
        'implementation('
        '"com.solanamobile:mobile-wallet-adapter-clientlib-ktx:2.1.0")',
      ),
    );
    expect(activity, contains('SolanaMwaBridge('));
    expect(rootGradle, contains('LibraryAndroidComponentsExtension'));
    expect(rootGradle, contains('finalizeDsl'));
    expect(
        activity, contains('class MainActivity : FlutterFragmentActivity()'));
    expect(activity, isNot(contains('class MainActivity : FlutterActivity()')));
    expect(activity, contains('.attach('));
    expect(RegExp(r'SolanaMwaBridge\(').allMatches(activity), hasLength(1));
  });

  test('MWA is Mainnet-only chooser routing with one tagged submission result',
      () {
    final source = read(
      'android/app/src/main/kotlin/com/openclaw/plawie/SolanaMwaBridge.kt',
    );
    final lower = source.toLowerCase();

    expect(source, contains('com.openclaw.plawie/solana_mwa'));
    expect(source, contains('MobileWalletAdapter('));
    expect(source, contains('ActivityResultSender(activity)'));
    expect(source, contains('Solana.Mainnet'));
    expect(source, contains('getCapabilities()'));
    expect(source, contains('ProtocolContract.FEATURE_ID_SIGN_TRANSACTIONS'));
    expect(source, isNot(contains('signTransactions(arrayOf(transaction))')));
    expect(source, contains('identityUri = Uri.parse("https://plawie.app")'));
    expect(source, contains('TransactionParams('));
    expect(
      source,
      contains('REQUIRED_MIN_CONTEXT_SLOT_COMPATIBILITY = 0'),
    );
    expect(source, contains('"confirmed"'));
    expect(source, contains('WALLET_SEND_MAX_RETRIES = 3'));
    expect(
      source,
      contains(
        'signAndSendTransactions(\n'
        '                arrayOf(transaction),\n'
        '                transactionParams,\n'
        '            )',
      ),
    );
    expect(source, contains('"mode" to "signAndSend"'));
    expect(source, contains('"signatureBase58"'));
    expect(source, contains('"authorize"'));
    expect(source, contains('"submitTransaction"'));
    expect(source, contains('"deauthorize"'));
    expect(source, contains('private class InvalidWalletPayloadException'));
    expect(source, contains('catch (_: InvalidWalletPayloadException)'));
    expect(source, isNot(contains('catch (_: IllegalArgumentException)')));
    expect(
      source,
      contains('is TransactionResult.Success -> result.success(null)'),
      reason: 'Kotlin Unit is not a Flutter StandardMessageCodec value.',
    );
    expect(source, isNot(contains('Log.')));
    expect(source, isNot(contains('"authToken"')));
    expect(source, isNot(contains('walletUriBase')));
    for (final brand in <String>[
      'phantom',
      'solflare',
      'jupiter',
      'trust wallet',
    ]) {
      expect(lower, isNot(contains(brand)));
    }
  });
}

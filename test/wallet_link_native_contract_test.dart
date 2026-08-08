import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  test('Android owns exactly one bounded wallet callback route', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    expect(manifest, contains('android:launchMode="singleTop"'));
    expect(
      manifest,
      contains(
        'android:name="flutter_deeplinking_enabled"\n'
        '                android:value="false"',
      ),
    );
    expect(
        RegExp('android:scheme="plawie"').allMatches(manifest), hasLength(1));
    expect(
      RegExp('android:host="wallet-callback"').allMatches(manifest),
      hasLength(1),
    );
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, isNot(contains('QUERY_ALL_PACKAGES')));
    for (final packageName in <String>[
      'io.metamask',
      'com.wallet.crypto.trustapp',
      'org.toshi',
      'app.phantom',
      'com.solflare.mobile',
    ]) {
      expect(manifest, contains('android:name="$packageName"'));
    }
  });

  test('Reown uses the native callback until universal links are verified', () {
    final runtime = read(
      'lib/services/bridge/bridge_funding_runtime.dart',
    );

    expect(runtime, contains('native: walletRedirect'));
    expect(runtime, isNot(contains('universal: dappUri.toString()')));
    expect(runtime, isNot(contains('linkMode: true')));
  });

  test(
      'one callback owner handles current and new intents without logging URIs',
      () {
    final bridge = read(
      'android/app/src/main/kotlin/com/openclaw/plawie/WalletLinkBridge.kt',
    );
    final activity = read(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    );

    expect(bridge, contains('com.openclaw.plawie/wallet_links'));
    expect(bridge, contains('com.openclaw.plawie/wallet_links_control'));
    expect(bridge, contains('Intent.ACTION_VIEW'));
    expect(bridge, contains('uri.scheme != "plawie"'));
    expect(bridge, contains('uri.host != "wallet-callback"'));
    expect(bridge, contains('pendingInitialLink'));
    expect(
      RegExp(
        r'fun onNewIntent\(intent: Intent\?\).*?'
        r'if \(sink == null\).*?pendingInitialLink = link',
        dotAll: true,
      ).hasMatch(bridge),
      isTrue,
      reason: 'A callback received before Dart listens must not be dropped.',
    );
    expect(bridge, contains('"initialLink"'));
    expect(bridge, contains('EventChannel'));
    expect(bridge, contains('MethodChannel'));
    expect(bridge, isNot(contains('Log.')));

    expect(activity, contains('WalletLinkBridge('));
    expect(activity, contains('.captureInitialIntent(intent)'));
    expect(activity, contains('walletLinkBridge?.onNewIntent(intent)'));
    expect(
      RegExp(r'override fun onNewIntent\(intent: Intent\)')
          .allMatches(activity),
      hasLength(1),
    );
  });
}

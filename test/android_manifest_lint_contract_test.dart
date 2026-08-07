import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest declares only real services and optional camera hardware', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(manifest, isNot(contains('android:name=".GatewayService"')));
    expect(manifest, contains('android:name="android.hardware.camera"'));
    expect(manifest, contains('android:required="false"'));
  });

  test('app-only dynamic broadcasts use the compat non-exported contract', () {
    final source = File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      'ContextCompat.registerReceiver'.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      'ContextCompat.RECEIVER_NOT_EXPORTED'.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      source,
      isNot(contains(
        'registerReceiver(pipMicReceiver, IntentFilter(ACTION_PIP_MIC))',
      )),
    );
    expect(
      source,
      isNot(contains('registerReceiver(wakeWordReceiver, wakeFilter)')),
    );
  });

  test('Android lint only suppresses Flutter local-properties path escaping', () {
    final gradle = File('android/app/build.gradle.kts')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(gradle, contains('disable += "PropertyEscape"'));
    expect(
      RegExp(r'disable\s*\+=').allMatches(gradle).length,
      equals(1),
    );
  });
}

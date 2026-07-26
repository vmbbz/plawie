import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VRM module publishes readiness only after its callable APIs exist', () {
    final html = File('assets/vrm/avatar_scene.html').readAsStringSync();
    final loadApi = html.indexOf('window.loadVrmAvatar =');
    final gestureApi = html.indexOf('window.playGestureCommand =');
    final moduleReady = html.indexOf('window._plawieModuleReady = true;');

    expect(loadApi, greaterThanOrEqualTo(0));
    expect(gestureApi, greaterThan(loadApi));
    expect(moduleReady, greaterThan(gestureApi));
    expect(html, contains("postMessage('MODULE_READY')"));
    expect(html, isNot(contains("postMessage('READY')")));
  });

  test('mobile VRM renderer uses the bounded production profile', () {
    final html = File('assets/vrm/avatar_scene.html').readAsStringSync();

    expect(
      html,
      contains('Math.min(window.devicePixelRatio || 1, 1.5)'),
    );
    expect(html, contains('antialias: !IS_MOBILE_RENDERER'));
    expect(
      html,
      contains('IS_MOBILE_RENDERER ? "low-power" : "high-performance"'),
    );
  });
}

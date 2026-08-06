import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android approval surface blocks capture and obscured-window taps',
      () async {
    final activity = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();
    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();
    final bridge = await File('lib/services/native_bridge.dart').readAsString();

    expect(activity, contains('"setSensitiveUiVisible"'));
    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
    expect(activity, contains('filterTouchesWhenObscured = visible'));
    expect(activity, contains('window.setHideOverlayWindows(visible)'));
    expect(
      manifest,
      contains('android.permission.HIDE_OVERLAY_WINDOWS'),
    );
    expect(bridge, contains('setSensitiveUiVisible'));
  });
}

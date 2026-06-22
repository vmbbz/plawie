import 'package:flutter/services.dart';

class CanvasScreenshotChannel {
  static const _channel =
      MethodChannel('com.nxg.openclawproot/canvas_screenshot');

  /// Request a native PixelCopy screenshot of the canvas WebView.
  /// Returns PNG bytes or null if capture fails.
  static Future<Uint8List?> captureScreenshot(int viewId) async {
    try {
      final result = await _channel.invokeMethod<Uint8List?>(
        'captureScreenshot',
        {'viewId': viewId},
      );
      return result;
    } catch (e) {
      return null;
    }
  }
}

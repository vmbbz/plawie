import 'package:clawa/services/capabilities/canvas_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CanvasCapability().setPluginSurfaceUrl(null);
  });

  test('resolves relative canvas paths through node-scoped plugin surface', () {
    final capability = CanvasCapability()
      ..setPluginSurfaceUrl('http://127.0.0.1:18789/__openclaw__/cap/abc123');

    final resolved = capability.resolveCanvasUrl(
      '/__openclaw__/canvas/tree.html?frame=1#preview',
    );

    expect(
      resolved.toString(),
      'http://127.0.0.1:18789/__openclaw__/cap/abc123/__openclaw__/canvas/tree.html?frame=1#preview',
    );
  });

  test('rewrites raw local gateway canvas URLs to plugin surface URLs', () {
    final capability = CanvasCapability()
      ..setPluginSurfaceUrl('http://127.0.0.1:18789/__openclaw__/cap/abc123');

    final resolved = capability.resolveCanvasUrl(
      'http://localhost:18789/__openclaw__/canvas/tree.html',
    );

    expect(
      resolved.toString(),
      'http://127.0.0.1:18789/__openclaw__/cap/abc123/__openclaw__/canvas/tree.html',
    );
    expect(resolved.queryParameters, isNot(contains('token')));
  });

  test('leaves non-canvas external URLs untouched', () {
    final capability = CanvasCapability()
      ..setPluginSurfaceUrl('http://127.0.0.1:18789/__openclaw__/cap/abc123');

    final resolved = capability.resolveCanvasUrl('https://example.com/app');

    expect(resolved.toString(), 'https://example.com/app');
  });
}

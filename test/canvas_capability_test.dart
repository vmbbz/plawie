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

  test('rejects an unscoped local canvas URL instead of loading Unauthorized',
      () {
    final capability = CanvasCapability();

    expect(
      () => capability.resolveCanvasUrl(
        'http://localhost:18789/__openclaw__/canvas/tree.html',
      ),
      throwsStateError,
    );
  });

  test('centering contract only targets the canvas presentation visual', () {
    final capability = CanvasCapability();
    final script = capability.canvasVisualCenteringScript;

    expect(script, contains("body.style.display = 'flex'"));
    expect(script, contains("body.style.alignItems = 'center'"));
    expect(script, contains("body.style.justifyContent = 'center'"));
    expect(script, contains("target.style.objectFit = 'contain'"));
    expect(script, contains("children.length !== 1"));
  });

  test('canvas surface detection excludes ordinary external pages', () {
    final capability = CanvasCapability();

    expect(
      capability.isCanvasSurfaceUrl(
        'http://127.0.0.1:18789/__openclaw__/canvas/tree.html',
      ),
      isTrue,
    );
    expect(
      capability.isCanvasSurfaceUrl('https://example.com/app'),
      isFalse,
    );
  });
}

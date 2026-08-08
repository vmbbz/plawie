import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('terminal uses one persistent user-demand rollback shell', () {
    final terminal = File('lib/screens/terminal_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(terminal, contains('NativeBridge.executeInShell('));
    expect(terminal, isNot(contains('NativeBridge.runInProot(')));
    expect(terminal, contains('PRoot fallback starts only when you run'));
    expect(terminal, contains('final FocusNode _historyFocusNode'));
    expect(terminal, contains('NativeBridge.destroyShell()'));
  });

  test('every PRoot process repairs the versioned talloc alias first', () {
    final processManager = File(
      'android/app/src/main/kotlin/com/openclaw/plawie/ProcessManager.kt',
    ).readAsStringSync();

    expect(processManager, contains('ensureProotRuntimeLibraries()'));
    expect(processManager, contains('File(targetDir, "libtalloc.so.2")'));
    expect(processManager, contains('source.copyTo(target, overwrite = true)'));
    expect(
      processManager.indexOf('ensureProotRuntimeLibraries()'),
      lessThan(processManager.indexOf('return mapOf(')),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('terminal uses bounded user-demand rollback processes', () {
    final terminal = File('lib/screens/terminal_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(terminal, contains('NativeBridge.runInProot('));
    expect(terminal, contains('timeout: 120'));
    expect(terminal, contains('NativeBridge.getBootstrapStatus()'));
    expect(terminal, contains("status['binBashExists'] == true"));
    expect(terminal, contains('Open rollback setup'));
    expect(terminal, contains('const SetupWizardScreen()'));
    expect(terminal, isNot(contains('NativeBridge.executeInShell(')));
    expect(terminal, contains('It starts only when you run a command.'));
    expect(terminal, contains('final FocusNode _historyFocusNode'));
    expect(terminal, isNot(contains('NativeBridge.destroyShell()')));
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

  test('native process boundary rejects an absent rollback rootfs clearly', () {
    final processManager = File(
      'android/app/src/main/kotlin/com/openclaw/plawie/ProcessManager.kt',
    ).readAsStringSync();

    expect(processManager, contains('ensureProotRootfsReady()'));
    expect(processManager, contains('File(rootfsDir, "bin/bash").isFile'));
    expect(
      processManager,
      contains('Optional PRoot rollback is not installed.'),
    );
  });
}

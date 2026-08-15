import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard app pages share the compact header metric', () {
    const standardPages = <String>[
      'lib/screens/base_screen.dart',
      'lib/screens/help_screen.dart',
      'lib/screens/logs_screen.dart',
      'lib/screens/node_screen.dart',
      'lib/screens/packages_screen.dart',
      'lib/screens/package_install_screen.dart',
      'lib/screens/settings_screen.dart',
      'lib/screens/terminal_screen.dart',
      'lib/screens/management/bot_management_dashboard.dart',
      'lib/screens/management/skills_manager.dart',
      'lib/screens/management/skills/agent_base_page.dart',
      'lib/screens/management/skills/agent_calls_page.dart',
      'lib/screens/management/skills/agent_credit_page.dart',
      'lib/screens/management/skills/agent_wallet_page.dart',
      'lib/screens/management/skills/agent_work_page.dart',
    ];

    for (final path in standardPages) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('expandedHeight: AppLayout.standardSliverHeaderHeight'),
        reason: path,
      );
    }
  });

  test('wallet halves its post-header top inset', () {
    final constants = File('lib/constants.dart').readAsStringSync();
    final wallet = File('lib/screens/base_screen.dart').readAsStringSync();

    expect(constants, contains('standardSliverHeaderHeight = 72'));
    expect(constants, contains('pageTopInset = 12'));
    expect(wallet, contains('AppLayout.pageTopInset'));
  });
}

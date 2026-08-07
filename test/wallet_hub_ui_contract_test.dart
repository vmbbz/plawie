import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wallet hub exposes three networks without weakening Base-only payments',
      () {
    final source = File('lib/screens/base_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(source, contains("'WALLET'"));
    expect(source, contains('PopupMenuButton<WalletNetwork>'));
    expect(source, contains('WalletNetworkPolicy.values'));
    expect(source, contains('_baseService.isBaseMainnet'));
    expect(source, contains('baseMainnetSelected: _baseService.isBaseMainnet'));
    expect(source, isNot(contains('PopupMenuButton<bool>')));
    expect(source, isNot(contains('!_baseService.useSepolia')));
  });

  test('wallet hub keeps Base USDC and Robinhood USDG visibly distinct', () {
    final source = File('lib/screens/base_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(source, contains("title: 'Send \${stablecoin.symbol}'"));
    expect(source, contains("symbol == 'USDG' ? 'send_usdg' : 'send_usdc'"));
    expect(source, contains('await _baseService.sendUsdg'));
    expect(source, contains('_baseService.stablecoinBalance'));
    expect(
        source, contains('Same secured address across supported EVM networks'));
  });

  test('dashboard and settings use the Wallet-facing product name', () {
    final dashboard = File('lib/screens/dashboard_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final settings = File('lib/screens/settings_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(dashboard, contains("title: 'Wallet'"));
    expect(dashboard, contains("subtitle: 'Base · Robinhood'"));
    expect(settings, contains("Text('AI Payments & Wallet')"));
    expect(settings, contains('finish setup in Wallet'));
  });

  test('wallet skill contract exposes Robinhood and USDG explicitly', () {
    final skills = File('lib/services/skills_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final router = File('lib/services/app_native_chat_tool_router.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(skills, contains("case 'send_usdg':"));
    expect(skills, contains("'mainnet', 'sepolia', 'robinhood'"));
    expect(router, contains("'network': lower.contains('robinhood')"));
    expect(router, contains("'USDG'"));
  });
}

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
    expect(source, contains("'wallet-network-\${definition.storageValue}'"));
    expect(source, contains("WalletNetwork.robinhoodMainnet => 'Robinhood'"));
    expect(
      source,
      contains(
        'This does not replace its private key or address.',
      ),
    );
    expect(source, contains('_baseService.isBaseMainnet'));
    expect(source, contains('baseMainnetSelected: _baseService.isBaseMainnet'));
    expect(source, contains("'wallet-default-network-control'"));
    expect(source, contains("'make-current-wallet-network-default'"));
    expect(source, contains('_baseService.setDefaultWalletNetwork('));
    expect(source, contains("'Use current'"));
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
    expect(source, contains("'NETWORK BALANCE'"));
    expect(source, contains("'SECURED ACCOUNT'"));
    expect(source, contains('selectedNetwork.name'));
    expect(source, contains('approval required to sign'));
    expect(source, isNot(contains("'Plawie Wallet'")));
    expect(source, contains('official USDG'));
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
    expect(dashboard, contains('iconColor: const Color(0xFF0052FF)'));
    expect(settings, contains("Text('AI Payments & Wallet')"));
    expect(settings, contains('finish setup in Wallet'));
  });

  test('wallet skill page points users to the visible network controls', () {
    final source = File('lib/screens/management/skills/agent_base_page.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(source, contains("'Wallet Networks'"));
    expect(source, contains("'Switch Base / Robinhood network'"));
    expect(source, contains('Viewing \${_baseService.networkName}'));
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

  test('provider top-up defaults to direct Base USDC funding', () {
    final screen = File('lib/screens/base_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final wallet = File('lib/services/base_service.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(screen, contains('ProviderTopUpFundingCoordinator('));
    expect(
        screen, contains('initialSourceChainId: BridgeConstants.baseChainId'));
    expect(screen, contains("initialSourceTokenSymbol: 'USDC'"));
    expect(screen, contains('Use Base USDC from another wallet'));
    expect(screen, contains('onFundingCompleted: (_)'));
    expect(wallet, contains('refreshBaseUsdcBalanceUnitsForPayment'));
    expect(
      wallet,
      contains(
          'Refresh Base Mainnet USDC for a payment decision and fail closed.'),
    );
  });

  test('wallet hub distinguishes payment-wallet and provider balances', () {
    final screen = File('lib/screens/base_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    final bridge = File('lib/widgets/bridge_funding_panel.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');

    expect(screen, contains("'BASE PAYMENT WALLET'"));
    expect(screen,
        contains("'This Base USDC is already the BlockRun payment balance."));
    expect(screen, contains("'Top up'"));
    expect(bridge, contains("'Base funding confirmed'"));
    expect(screen, contains("Uri.https('basescan.org', '/tx/\$hash')"));
  });
}

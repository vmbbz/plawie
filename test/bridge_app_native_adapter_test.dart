import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/bridge_quote_service.dart';

void main() {
  const evmAddress = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';

  test('routes a complete Robinhood bridge request to a read-only quote', () {
    final target = AppNativeChatToolRouter.instance.requiredGatewayNodeTarget(
      'Bridge 0.01 ETH from Robinhood Chain to Base from $evmAddress',
    );

    expect(target, isNotNull);
    expect(target!['command'], 'bridge.quote');
    final params = jsonDecode(
      target['nodesInput']['invokeParamsJson'] as String,
    ) as Map<String, dynamic>;
    expect(params['sourceChainId'], BridgeQuoteService.robinhoodChainId);
    expect(params['sourceToken'], 'ETH');
    expect(params['amount'], '0.01');
    expect(params['sourceAddress'], evmAddress);
  });

  test('preserves case-sensitive Solana source addresses', () {
    const solanaAddress = '11111111111111111111111111111111';
    final target = AppNativeChatToolRouter.instance.requiredGatewayNodeTarget(
      'Bridge 1 SOL from Solana into Base from $solanaAddress',
    );

    expect(target, isNotNull);
    expect(target!['command'], 'bridge.quote');
    final params = jsonDecode(
      target['nodesInput']['invokeParamsJson'] as String,
    ) as Map<String, dynamic>;
    expect(params['sourceChainId'], BridgeQuoteService.solanaChainId);
    expect(params['sourceAddress'], solanaAddress);
  });

  test('incomplete bridge requests return capabilities without execution', () {
    final target = AppNativeChatToolRouter.instance.requiredGatewayNodeTarget(
      'How can I bridge from Robinhood Chain to Base?',
    );

    expect(target, isNotNull);
    expect(target!['command'], 'bridge.capabilities');
    final params = jsonDecode(
      target['nodesInput']['invokeParamsJson'] as String,
    ) as Map<String, dynamic>;
    expect(params.keys, <String>['routingSource']);
  });

  test('payment and bridge commands are registered on the live node', () async {
    final source =
        (await File('lib/providers/node_provider.dart').readAsString())
            .replaceAll('\r\n', '\n');

    expect(source, contains('final _aiPaymentsCapability'));
    expect(
      source,
      contains('_registerCapabilityAliases(\n      _aiPaymentsCapability,'),
    );
    expect(source, contains("'payments.capabilities'"));
    expect(source, contains("'bridge.quote'"));
    expect(source, contains('if (command.contains(\'.\'))'));
  });
}

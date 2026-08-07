import 'dart:io';

import 'package:clawa/services/capabilities/ai_payments_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('node command upgrades use the official node pairing approval RPC',
      () async {
    final gatewaySource =
        await File('lib/services/gateway_service.dart').readAsString();
    final nodeSource =
        await File('lib/services/node_service.dart').readAsString();

    expect(gatewaySource, contains("invoke('node.pair.approve'"));
    expect(gatewaySource, contains("invoke('device.pair.approve'"));
    expect(
      gatewaySource,
      contains('approveNodeCommandPairingRequestViaGateway'),
    );
    expect(
      nodeSource,
      contains('Gateway approved the complete node command snapshot'),
    );
    expect(
      nodeSource,
      contains('if (await _pairedNodeCommandsCoverDeclared())'),
    );
    expect(nodeSource, isNot(contains('_nativeStoredContractAlreadyAccepted')));
    expect(nodeSource, contains("return 'v7:"));
    expect(nodeSource, contains("'devices/pending.json'"));
    expect(nodeSource, contains("record['nodeId']?.toString()"));
  });

  test('advertised mobile command contract includes every avatar command', () {
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      containsAll(const [
        'avatar.gesture',
        'avatar.sequence',
        'avatar.mode',
        'avatar.model',
        'avatar.status',
        'avatar_gesture',
        'avatar_sequence',
        'avatar_mode',
        'avatar_model',
        'avatar_status',
      ]),
    );
  });

  test('payment and bridge node commands are explicitly allowlisted', () {
    final capability = AiPaymentsCapability();
    final declaredCommands = <String>{};

    for (final command in capability.commands) {
      if (command.contains('.')) {
        declaredCommands.add(command);
      } else {
        declaredCommands.add('${capability.name}.$command');
        declaredCommands.add('${capability.name}_$command');
      }
    }

    expect(
      declaredCommands,
      equals(const <String>{
        'payments.capabilities',
        'payments.status',
        'payments.receipts',
        'payments_capabilities',
        'payments_status',
        'payments_receipts',
        'bridge.capabilities',
        'bridge.quote',
        'bridge.status',
        'bridge.receipts',
      }),
    );
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      containsAll(declaredCommands),
    );
    for (final forbiddenCommand in const <String>[
      'payments.approve',
      'payments.sign',
      'payments.submit',
      'bridge.execute',
      'bridge.connect',
      'bridge.approve',
      'bridge.sign',
      'bridge.submit',
      'bridge.broadcast',
      'bridge.deposit.create',
    ]) {
      expect(declaredCommands, isNot(contains(forbiddenCommand)));
      expect(
        GatewayToolCatalog.mobileNodeAllowCommands,
        isNot(contains(forbiddenCommand)),
      );
    }
  });
}

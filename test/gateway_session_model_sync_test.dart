import 'dart:io';

import 'package:clawa/services/gateway_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud selection always produces authoritative session metadata', () {
    final gateway = GatewayService();

    expect(
      gateway.debugSessionModelMetadataForTesting(
        'venice/gemini-3-6-flash',
      ),
      const {'model': 'venice/gemini-3-6-flash'},
    );
    expect(
      gateway.debugSessionModelMetadataForTesting(
        'blockrun/openai/gpt-5.6-luna',
      ),
      const {'model': 'blockrun/openai/gpt-5.6-luna'},
    );
  });

  test('agent and direct local routes never patch the Gateway session model',
      () {
    final gateway = GatewayService();

    expect(
      gateway.debugSessionModelMetadataForTesting('agent/researcher'),
      isEmpty,
    );
    expect(
      gateway.debugSessionModelMetadataForTesting('local-llm/qwen2.5-1.5b'),
      isEmpty,
    );
  });

  test('sendMessage patches the live session after readiness and before send',
      () async {
    final source =
        await File('lib/services/gateway_service.dart').readAsString();
    final methodStart = source.indexOf('Stream<String> sendMessage(');
    final methodEnd = source.indexOf(
      '  Future<Map<String, dynamic>> _syncModelToConfig',
      methodStart,
    );
    expect(methodStart, isNonNegative);
    expect(methodEnd, isNonNegative);
    final send = source.substring(methodStart, methodEnd);
    final syncBlock = send.lastIndexOf('if (modelSyncChanges.isNotEmpty &&');
    final readiness = send.indexOf(
      '_waitForGatewayChatLaneReady(token)',
      syncBlock,
    );
    final patch = send.indexOf('_patchActiveGatewaySessionModel(', syncBlock);
    final frame = send.indexOf('final chatSendFrame');

    expect(syncBlock, isNonNegative);
    expect(readiness, isNonNegative);
    expect(patch, greaterThan(readiness));
    expect(frame, greaterThan(patch));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/gateway_service.dart';
import 'package:clawa/services/native_clawhub_skill_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GatewayService required native skill intent executes stocks', () async {
    final temp =
        await Directory.systemTemp.createTemp('gateway_stocks_intent_');
    addTearDown(() => temp.delete(recursive: true));

    final scripts = Directory(
      '${temp.path}/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/scripts',
    );
    await scripts.create(recursive: true);
    await File('${scripts.path}/yfinance_ai.py').writeAsString('# stub');

    final service = NativeClawHubSkillExecutionService.test(
      filesDirProvider: () async => temp.path,
      pythonRunner: (_) async => {
        'ok': true,
        'exitCode': 0,
        'stdout': jsonEncode({
          'NVDA': '**NVDA - NVIDIA Corporation**\n\n**Current Price:** 123.45',
        }),
        'stderr': '',
      },
    );

    final execution = await GatewayService()
        .debugExecuteRequiredNativeClawHubSkillIntentForTesting(
      'Use the stocks skill to get current NVDA price. No web fallback.',
      service: service,
    );

    expect(execution, isNotNull);
    expect(execution!.ok, isTrue);
    expect(execution.toolName, 'stocks');
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:stocks:'));
    expect(execution.toolResultChunk, startsWith('\x00TOOL_RESULT:stocks:'));
    expect(execution.visibleText, contains('NVDA'));
  });
}

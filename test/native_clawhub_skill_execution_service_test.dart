import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/native_clawhub_skill_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stocks intent parses stock and crypto symbols in order', () {
    final intent = NativeClawHubSkillExecutionService.parseStocksIntent(
        'Use the stocks skill to get current NVDA and BTC prices.');

    expect(intent, isNotNull);
    expect(
      intent!.actions.map((action) => action.toJson()).toList(),
      [
        {
          'label': 'NVDA',
          'method': 'get_stock_price',
          'args': {'ticker': 'NVDA'},
        },
        {
          'label': 'BTC',
          'method': 'get_crypto_price',
          'args': {'symbol': 'BTC'},
        },
      ],
    );
  });

  test('stocks execution calls native python runner with workspace script path',
      () async {
    final temp = await Directory.systemTemp.createTemp('native_skill_exec_');
    addTearDown(() => temp.delete(recursive: true));

    final skillDir = Directory(
      '${temp.path}/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/scripts',
    );
    await skillDir.create(recursive: true);
    await File('${skillDir.path}/yfinance_ai.py').writeAsString('# stub');

    Map<String, dynamic>? capturedPayload;
    final service = NativeClawHubSkillExecutionService.test(
      filesDirProvider: () async => temp.path,
      pythonRunner: (payload) async {
        capturedPayload = payload;
        return {
          'ok': true,
          'exitCode': 0,
          'stdout': jsonEncode({
            'NVDA':
                '**NVDA - NVIDIA Corporation**\n\n **Current Price:** \$1.23',
            'BTC': '** Cryptocurrency: BTC-USD**\n\n** Current Price:** \$4.56',
          }),
          'stderr': '',
        };
      },
    );

    final execution = await service.tryExecuteRequiredIntent(
      'Use the stocks skill to get current NVDA and BTC prices.',
    );

    expect(execution, isNotNull);
    expect(execution!.ok, isTrue);
    expect(execution.toolName, 'stocks');
    expect(execution.visibleText, contains('NVDA'));
    expect(execution.visibleText, contains('BTC'));
    expect(capturedPayload?['cwd'], contains('/workspace/skills/stocks'));
    expect(capturedPayload?['args'], isA<List>());
    expect(
      capturedPayload?['pythonPaths'].toString(),
      contains('/runtimes/python/site-packages'),
    );
  });
}

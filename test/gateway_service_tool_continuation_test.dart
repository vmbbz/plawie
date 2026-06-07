import 'package:clawa/services/gateway_service.dart';
import 'package:clawa/services/native_clawhub_skill_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required stocks result becomes Gateway continuation context', () {
    const execution = NativeClawHubSkillExecution(
      toolName: 'stocks',
      input: {
        'skill': 'stocks',
        'actions': [
          {
            'method': 'get_stock_price',
            'args': {'ticker': 'NVDA'},
          },
        ],
      },
      result: {
        'ok': true,
        'skill': 'stocks',
        'data': {
          'NVDA': '**Current Price:** 123.45',
        },
      },
      ok: true,
      visibleText: 'Stocks skill result:\n\nNVDA:\n**Current Price:** 123.45',
    );

    final prompt = GatewayService()
        .debugBuildRequiredNativeSkillContinuationMessageForTesting(
      'Use the stocks skill to get current NVDA price. No web fallback.',
      execution,
    );

    expect(prompt, contains('Use the stocks skill'));
    expect(prompt, contains('TOOL_USE:stocks'));
    expect(prompt, contains('TOOL_RESULT:stocks'));
    expect(prompt, contains('123.45'));
    expect(prompt, contains('answer from the tool result'));
    expect(prompt, isNot(equals(execution.visibleText)));
    expect(prompt.length, lessThan(16000));
  });
}

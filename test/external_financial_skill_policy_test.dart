import 'package:clawa/services/external_financial_skill_policy.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('known external financial wallet skill aliases fail closed', () {
    for (final slug in const [
      'moonpay',
      'moonpay@0.6.24',
      'kevarifin14/moonpay',
      '@community/moonpay',
      'x402-client',
      'marketingkioldenburg/x402-client',
      'agentkit',
      'cdp_agentkit',
      'coinbase-agentkit',
      'agent-card',
      'agentcard',
    ]) {
      expect(
        ExternalFinancialSkillPolicy.isInstallBlocked(slug),
        isTrue,
        reason: slug,
      );
      expect(
        ExternalFinancialSkillPolicy.installBlockReason(slug),
        isNotEmpty,
        reason: slug,
      );
    }

    expect(
      ExternalFinancialSkillPolicy.isInstallBlocked('weather'),
      isFalse,
    );
  });

  test('external connector method allowlists contain reads only', () {
    expect(
      ExternalFinancialSkillPolicy.agentCardReadMethods,
      const ['get_balance'],
    );
    expect(
      ExternalFinancialSkillPolicy.moonPayReadMethods,
      const ['get_portfolio', 'get_price', 'dca_list'],
    );

    for (final method in const [
      'create_card',
      'set_refill_policy',
      'add_funds',
      'spend',
    ]) {
      expect(
        ExternalFinancialSkillPolicy.canExecuteAgentCardMethod(method),
        isFalse,
        reason: method,
      );
    }
    for (final method in const [
      'swap',
      'bridge',
      'buy',
      'sell',
      'transfer',
      'dca_create',
      'sign',
    ]) {
      expect(
        ExternalFinancialSkillPolicy.canExecuteMoonPayMethod(method),
        isFalse,
        reason: method,
      );
    }
  });

  test('bundled tool catalog advertises only read-only connector methods',
      () async {
    await SkillsService().initialize();
    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();

    List<dynamic> methodsFor(String skillId) {
      final tool = catalog.singleWhere((entry) => entry['name'] == skillId);
      final schema = tool['input_schema'] as Map<String, dynamic>;
      final properties = schema['properties'] as Map<String, dynamic>;
      final method = properties['method'] as Map<String, dynamic>;
      return method['enum'] as List<dynamic>;
    }

    expect(methodsFor('agent-card'), const ['get_balance']);
    expect(
      methodsFor('moonpay'),
      const ['get_portfolio', 'get_price', 'dca_list'],
    );
  });

  test('direct external connector writes fail before Gateway execution',
      () async {
    await SkillsService().initialize();

    final cardResult = await SkillsService().executeSkill(
      'agent-card',
      parameters: const {'method': 'create_card'},
    );
    final moonPayResult = await SkillsService().executeSkill(
      'moonpay',
      parameters: const {'method': 'swap'},
    );

    expect(cardResult.success, isFalse);
    expect(cardResult.error, contains('HUMAN_APPROVAL_BOUNDARY'));
    expect(moonPayResult.success, isFalse);
    expect(moonPayResult.error, contains('HUMAN_APPROVAL_BOUNDARY'));
  });

  test('blocked install returns before owner or workspace mutation', () async {
    await SkillsService().initialize();

    for (final slug in const ['moonpay', 'x402-client', 'cdp-agentkit']) {
      final report = await SkillsService().installSkillDetailed(
        slug,
        silent: true,
      );
      expect(report.ok, isFalse, reason: slug);
      expect(report.error, isNotEmpty, reason: slug);
      expect(report.targetPath, isNull, reason: slug);
    }
  });
}

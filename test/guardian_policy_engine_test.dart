import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/sibyl_memory_service.dart';
import 'package:clawa/services/guardian_policy_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuardianPolicyEngine Unit Tests', () {
    late SibylMemoryService memoryService;
    late GuardianPolicyEngine policyEngine;

    setUp(() async {
      memoryService = SibylMemoryService.inMemoryForTesting();
      await memoryService.initialize();
      policyEngine = GuardianPolicyEngine(memoryService: memoryService);
    });

    test('Allows transfers within policy limits', () async {
      final policy = GuardianPolicy(
        dailyLimitUsdc: 100.0,
        singleTxLimitUsdc: 50.0,
        allowedRecipients: ['0x1234567890123456789012345678901234567890', 'alice.base.eth'],
      );
      await memoryService.savePolicy(policy);

      final result = await policyEngine.evaluateTransaction(
        action: 'send_usdc',
        recipient: 'alice.base.eth',
        amountUsdc: 25.0,
      );

      expect(result.isAllowed, isTrue);
      expect(result.reason, contains('POLICY APPROVED'));
    });

    test('Rejects transfers exceeding single transaction limit', () async {
      final policy = GuardianPolicy(
        dailyLimitUsdc: 100.0,
        singleTxLimitUsdc: 25.0,
        allowedRecipients: [],
      );
      await memoryService.savePolicy(policy);

      final result = await policyEngine.evaluateTransaction(
        action: 'send_usdc',
        recipient: 'bob.base.eth',
        amountUsdc: 40.0,
      );

      expect(result.isAllowed, isFalse);
      expect(result.reason, contains('exceeds single-transaction limit'));
    });

    test('Rejects transfers exceeding cumulative daily cap', () async {
      final policy = GuardianPolicy(
        dailyLimitUsdc: 50.0,
        singleTxLimitUsdc: 40.0,
        allowedRecipients: [],
      );
      await memoryService.savePolicy(policy);

      // Journal a previous transaction of $30 today
      await memoryService.journalTransaction(BaseTxJournalEntry(
        txHash: '0xabc123',
        action: 'send_usdc',
        recipient: 'alice.base.eth',
        amountUsdc: 30.0,
        status: 'executed',
        policyDecisionReason: 'Pre-existing spend',
      ));

      // Try sending another $30 (Total $60 > $50 cap)
      final result = await policyEngine.evaluateTransaction(
        action: 'send_usdc',
        recipient: 'bob.base.eth',
        amountUsdc: 30.0,
      );

      expect(result.isAllowed, isFalse);
      expect(result.reason, contains('exceeds daily spending limit'));
    });

    test('Rejects unauthorized recipient when allowlist is active', () async {
      final policy = GuardianPolicy(
        dailyLimitUsdc: 100.0,
        singleTxLimitUsdc: 50.0,
        allowedRecipients: ['trusted.base.eth'],
      );
      await memoryService.savePolicy(policy);

      final result = await policyEngine.evaluateTransaction(
        action: 'send_usdc',
        recipient: 'untrusted_hacker.eth',
        amountUsdc: 10.0,
      );

      expect(result.isAllowed, isFalse);
      expect(result.reason, contains('not in your approved allowlist'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/commerce_fee_policy.dart';
import 'package:clawa/services/commerce_receipt.dart';
import 'package:clawa/services/x402_payment_service.dart';

void main() {
  final recordedAt = DateTime.utc(2026, 8, 15, 12);

  test('projects an x402 receipt without claiming platform revenue', () {
    final commerce = CommerceReceipt.fromX402(
      X402PaymentReceipt(
        intentId: 'intent-1',
        state: X402PaymentState.settled,
        recordedAt: recordedAt,
        transactionHash: '0x${'a' * 64}',
        payer: '0x${'b' * 40}',
        providerId: 'venice',
        network: 'eip155:8453',
        asset: X402PaymentPolicy.usdc,
        amount: '5000000',
        payTo: '0x${'c' * 40}',
        resourceUrl: 'https://api.venice.ai/api/v1/x402/top-up',
        challengeHash: 'private-challenge-hash',
      ),
    );

    expect(commerce.receiptId, 'x402:intent-1');
    expect(commerce.lane, CommerceLane.providerTopUp);
    expect(commerce.status, CommerceReceiptStatus.settled);
    expect(commerce.grossAmountUnits, BigInt.from(5000000));
    expect(commerce.platformFeeUnits, BigInt.zero);
    expect(commerce.netAmountUnits, BigInt.from(5000000));
    expect(commerce.toJson(), isNot(contains('payer')));
    expect(commerce.toJson(), isNot(contains('payTo')));
    expect(commerce.toJson(), isNot(contains('resourceUrl')));
    expect(commerce.toJson(), isNot(contains('challengeHash')));
  });

  test('round-trips a redacted receipt with integer amounts', () {
    final original = CommerceReceipt(
      receiptId: 'bridge:quote-1',
      lane: CommerceLane.bridge,
      status: CommerceReceiptStatus.quoted,
      recordedAt: recordedAt,
      asset: 'USDC',
      grossAmountUnits: BigInt.from(1000000),
      platformFeeUnits: BigInt.from(25000),
      netAmountUnits: BigInt.from(975000),
      network: 'eip155:8453',
      feeScheduleVersion: 3,
      quoteId: 'quote-1',
    );

    final restored = CommerceReceipt.fromJson(original.toJson());

    expect(restored.receiptId, original.receiptId);
    expect(restored.lane, original.lane);
    expect(restored.status, original.status);
    expect(restored.grossAmountUnits, original.grossAmountUnits);
    expect(restored.platformFeeUnits, original.platformFeeUnits);
    expect(restored.netAmountUnits, original.netAmountUnits);
    expect(restored.feeScheduleVersion, 3);
  });

  test('rejects a receipt whose fee and net do not reconcile', () {
    expect(
      () => CommerceReceipt(
        receiptId: 'bad',
        lane: CommerceLane.bridge,
        status: CommerceReceiptStatus.settled,
        recordedAt: recordedAt,
        asset: 'USDC',
        grossAmountUnits: BigInt.from(100),
        platformFeeUnits: BigInt.from(25),
        netAmountUnits: BigInt.from(80),
      ),
      throwsArgumentError,
    );
  });

  test('rejects malformed persisted receipts', () {
    expect(
      () => CommerceReceipt.fromJson(<String, dynamic>{
        'receiptId': 'broken',
        'lane': 'bridge',
        'status': 'settled',
        'recordedAt': recordedAt.toIso8601String(),
        'asset': 'USDC',
        'grossAmountUnits': 'not-an-integer',
        'platformFeeUnits': '0',
        'netAmountUnits': '0',
      }),
      throwsFormatException,
    );
  });
}

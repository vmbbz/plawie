import 'dart:typed_data';

import 'package:clawa/services/ai_payment_provider_catalog.dart';
import 'package:clawa/services/provider_top_up_funding_coordinator.dart';
import 'package:clawa/services/x402_payment_service.dart';
import 'package:clawa/services/x402_payment_transport_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final provider = AiPaymentProviderCatalog.byId('venice')!;

  test('sufficient balance preserves one challenge and skips funding',
      () async {
    final events = <String>[];
    final prepared = _payment('first', BigInt.from(5000000), provider);
    final coordinator = ProviderTopUpFundingCoordinator(
      prepare: (_) async {
        events.add('prepare:first');
        return prepared;
      },
      reject: (_) => events.add('reject'),
      selectBaseMainnet: () async => events.add('select-base'),
      refreshBaseUsdcBalance: () async {
        events.add('balance');
        return BigInt.from(5000000);
      },
      requestFunding: (_) async {
        events.add('fund');
        return true;
      },
      requestPaymentApproval: (payment) async {
        events.add('approve:${payment.intent.intentId}');
        return true;
      },
      submitPayment: (payment) async {
        events.add('submit:${payment.intent.intentId}');
        return _receipt(payment);
      },
    );

    final receipt = await coordinator.run(provider);

    expect(receipt?.state, X402PaymentState.settled);
    expect(events, <String>[
      'select-base',
      'prepare:first',
      'balance',
      'approve:first',
      'submit:first',
    ]);
  });

  test('insufficient challenge is destroyed before a cancelled funding modal',
      () async {
    final events = <String>[];
    final first = _payment('first', BigInt.from(5000000), provider);
    final coordinator = ProviderTopUpFundingCoordinator(
      prepare: (_) async => first,
      reject: (payment) => events.add('reject:${payment.intent.intentId}'),
      selectBaseMainnet: () async {},
      refreshBaseUsdcBalance: () async => BigInt.from(1000000),
      requestFunding: (requirement) async {
        events.add('fund:${requirement.requiredBaseUsdcDisplay}');
        return false;
      },
      requestPaymentApproval: (_) async => true,
      submitPayment: (_) async => throw StateError('must not submit'),
    );

    expect(await coordinator.run(provider), isNull);
    expect(events, <String>['reject:first', 'fund:5']);
  });

  test('completed funding uses a new challenge and separate approval',
      () async {
    final events = <String>[];
    final prepared = <PreparedX402Payment>[
      _payment('first', BigInt.from(5000000), provider),
      _payment('fresh', BigInt.from(5000000), provider),
    ];
    final balances = <BigInt>[BigInt.from(1000000), BigInt.from(6000000)];
    var prepareIndex = 0;
    var balanceIndex = 0;
    final coordinator = ProviderTopUpFundingCoordinator(
      prepare: (_) async {
        final payment = prepared[prepareIndex++];
        events.add('prepare:${payment.intent.intentId}');
        return payment;
      },
      reject: (payment) => events.add('reject:${payment.intent.intentId}'),
      selectBaseMainnet: () async => events.add('select-base'),
      refreshBaseUsdcBalance: () async => balances[balanceIndex++],
      requestFunding: (_) async {
        events.add('fund-completed');
        return true;
      },
      requestPaymentApproval: (payment) async {
        events.add('approve:${payment.intent.intentId}');
        return true;
      },
      submitPayment: (payment) async {
        events.add('submit:${payment.intent.intentId}');
        return _receipt(payment);
      },
    );

    final receipt = await coordinator.run(provider);

    expect(receipt?.intentId, 'fresh');
    expect(events, <String>[
      'select-base',
      'prepare:first',
      'reject:first',
      'fund-completed',
      'select-base',
      'prepare:fresh',
      'approve:fresh',
      'submit:fresh',
    ]);
  });

  test('completed route cannot continue with insufficient delivered balance',
      () async {
    final first = _payment('first', BigInt.from(5000000), provider);
    final balances = <BigInt>[BigInt.from(1000000), BigInt.from(4999999)];
    var balanceIndex = 0;
    final coordinator = ProviderTopUpFundingCoordinator(
      prepare: (_) async => first,
      reject: (_) {},
      selectBaseMainnet: () async {},
      refreshBaseUsdcBalance: () async => balances[balanceIndex++],
      requestFunding: (_) async => true,
      requestPaymentApproval: (_) async => true,
      submitPayment: (_) async => throw StateError('must not submit'),
    );

    await expectLater(
      coordinator.run(provider),
      throwsA(
        isA<ProviderTopUpFundingException>().having(
          (error) => error.code,
          'code',
          'BASE_USDC_STILL_INSUFFICIENT',
        ),
      ),
    );
  });

  test('increased fresh challenge is rejected before approval', () async {
    final rejected = <String>[];
    final prepared = <PreparedX402Payment>[
      _payment('first', BigInt.from(5000000), provider),
      _payment('fresh', BigInt.from(7000000), provider),
    ];
    final balances = <BigInt>[BigInt.from(1000000), BigInt.from(6000000)];
    var prepareIndex = 0;
    var balanceIndex = 0;
    final coordinator = ProviderTopUpFundingCoordinator(
      prepare: (_) async => prepared[prepareIndex++],
      reject: (payment) => rejected.add(payment.intent.intentId),
      selectBaseMainnet: () async {},
      refreshBaseUsdcBalance: () async => balances[balanceIndex++],
      requestFunding: (_) async => true,
      requestPaymentApproval: (_) async => throw StateError('no approval'),
      submitPayment: (_) async => throw StateError('no submit'),
    );

    await expectLater(
      coordinator.run(provider),
      throwsA(
        isA<ProviderTopUpFundingException>().having(
          (error) => error.code,
          'code',
          'FRESH_CHALLENGE_EXCEEDS_BALANCE',
        ),
      ),
    );
    expect(rejected, <String>['first', 'fresh']);
  });

  test('payment rejection destroys the approved-to-display challenge',
      () async {
    final rejected = <String>[];
    final prepared = _payment('first', BigInt.from(5000000), provider);
    final coordinator = ProviderTopUpFundingCoordinator(
      prepare: (_) async => prepared,
      reject: (payment) => rejected.add(payment.intent.intentId),
      selectBaseMainnet: () async {},
      refreshBaseUsdcBalance: () async => BigInt.from(5000000),
      requestFunding: (_) async => true,
      requestPaymentApproval: (_) async => false,
      submitPayment: (_) async => throw StateError('must not submit'),
    );

    expect(await coordinator.run(provider), isNull);
    expect(rejected, <String>['first']);
  });
}

PreparedX402Payment _payment(
  String id,
  BigInt amount,
  AiPaymentProviderOption provider,
) {
  final endpoint = provider.topUpEndpoint!;
  final now = DateTime.utc(2026, 8, 7, 12);
  return PreparedX402Payment(
    provider: provider,
    requestBody: Uint8List(0),
    intent: PendingPaymentIntent(
      intentId: id,
      approvalNonce: 'approval-$id',
      paymentNonce: '0x${'1' * 64}',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      requestMethod: 'POST',
      requestUrl: endpoint,
      requestBodyHash: 'body-$id',
      state: X402PaymentState.awaitingHumanApproval,
      challenge: X402PaymentChallenge(
        x402Version: 2,
        resource: <String, dynamic>{'url': endpoint.toString()},
        resourceUrl: endpoint,
        resourceDescription: 'Provider top-up',
        challengeHash: 'challenge-$id',
        requirement: X402PaymentRequirement(
          scheme: 'exact',
          network: X402PaymentPolicy.network,
          amount: amount.toString(),
          asset: X402PaymentPolicy.usdc,
          payTo: '0x2222222222222222222222222222222222222222',
          maxTimeoutSeconds: 300,
          extra: const <String, dynamic>{
            'assetTransferMethod': 'eip3009',
          },
        ),
      ),
    ),
  );
}

X402PaymentReceipt _receipt(PreparedX402Payment payment) => X402PaymentReceipt(
      intentId: payment.intent.intentId,
      state: X402PaymentState.settled,
      recordedAt: DateTime.utc(2026, 8, 7, 12, 1),
      providerId: payment.provider.id,
      amount: payment.intent.challenge.requirement.amount,
    );

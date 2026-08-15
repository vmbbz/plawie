import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/commerce_fee_policy.dart';

void main() {
  CommerceFeeSchedule schedule({
    CommerceAvailability availability = CommerceAvailability.enabled,
    int basisPoints = 250,
    BigInt? minimumFeeUnits,
    BigInt? maximumFeeUnits,
  }) {
    return CommerceFeeSchedule(
      lane: CommerceLane.bridge,
      version: 1,
      availability: availability,
      basisPoints: basisPoints,
      minimumFeeUnits: minimumFeeUnits,
      maximumFeeUnits: maximumFeeUnits,
    );
  }

  test('quotes basis points using integer token units', () {
    final quote = schedule().quote(BigInt.from(1000000));

    expect(quote.grossUnits, BigInt.from(1000000));
    expect(quote.feeUnits, BigInt.from(25000));
    expect(quote.netUnits, BigInt.from(975000));
  });

  test('rounds down fractional smallest units', () {
    final quote = schedule(basisPoints: 1).quote(BigInt.from(999));

    expect(quote.feeUnits, BigInt.zero);
    expect(quote.netUnits, BigInt.from(999));
  });

  test('applies a minimum fee only to a non-zero quote', () {
    final configured = schedule(
      basisPoints: 1,
      minimumFeeUnits: BigInt.from(10),
    );

    expect(configured.quote(BigInt.from(999)).feeUnits, BigInt.from(10));
    expect(configured.quote(BigInt.zero).feeUnits, BigInt.zero);
  });

  test('caps the fee at the configured maximum', () {
    final quote = schedule(
      basisPoints: 5000,
      maximumFeeUnits: BigInt.from(100),
    ).quote(BigInt.from(1000));

    expect(quote.feeUnits, BigInt.from(100));
    expect(quote.netUnits, BigInt.from(900));
  });

  test('fails closed before a partner agreement enables the schedule', () {
    expect(
      () => schedule(availability: CommerceAvailability.pendingPartner)
          .quote(BigInt.from(1000)),
      throwsStateError,
    );
    expect(
      () => schedule(availability: CommerceAvailability.disabled)
          .quote(BigInt.from(1000)),
      throwsStateError,
    );
  });

  test('rejects negative gross amounts', () {
    expect(
      () => schedule().quote(BigInt.from(-1)),
      throwsArgumentError,
    );
  });

  test('retains the lane and schedule version in the quote', () {
    final configured = CommerceFeeSchedule(
      lane: CommerceLane.avatarRental,
      version: 7,
      availability: CommerceAvailability.enabled,
      basisPoints: 100,
    );

    final quote = configured.quote(BigInt.from(10000));

    expect(quote.lane, CommerceLane.avatarRental);
    expect(quote.scheduleVersion, 7);
  });
}

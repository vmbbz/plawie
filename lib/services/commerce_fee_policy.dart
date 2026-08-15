// Pure, integer-safe fee policy primitives for future commerce integrations.
//
// This file deliberately contains no network calls, wallet addresses, payment
// signing, or provider secrets. A schedule is not enabled until an external
// partner agreement and the corresponding backend controls exist.

enum CommerceLane {
  providerTopUp,
  bridge,
  avatarMint,
  avatarRental,
}

enum CommerceAvailability {
  disabled,
  pendingPartner,
  enabled,
}

/// A fee schedule expressed in basis points and the smallest unit of the
/// settlement token. For example, 250 basis points is 2.5%.
class CommerceFeeSchedule {
  CommerceFeeSchedule({
    required this.lane,
    required this.version,
    required this.availability,
    required this.basisPoints,
    BigInt? minimumFeeUnits,
    this.maximumFeeUnits,
  })  : minimumFeeUnits = minimumFeeUnits ?? BigInt.zero,
        assert(version > 0, 'version must be positive'),
        assert(basisPoints >= 0 && basisPoints <= 10000,
            'basisPoints must be between 0 and 10000'),
        assert(minimumFeeUnits == null || minimumFeeUnits >= BigInt.zero,
            'minimumFeeUnits cannot be negative'),
        assert(maximumFeeUnits == null || maximumFeeUnits >= BigInt.zero,
            'maximumFeeUnits cannot be negative'),
        assert(
            maximumFeeUnits == null ||
                maximumFeeUnits >= (minimumFeeUnits ?? BigInt.zero),
            'maximumFeeUnits cannot be below minimumFeeUnits');

  final CommerceLane lane;
  final int version;
  final CommerceAvailability availability;
  final int basisPoints;
  final BigInt minimumFeeUnits;
  final BigInt? maximumFeeUnits;

  /// Quotes a fee without rounding through a floating-point currency value.
  ///
  /// Disabled and partner-pending schedules fail closed. This prevents a
  /// caller from accidentally presenting a fee as collectible before the
  /// relevant agreement, treasury, reconciliation, and disclosure controls
  /// are configured.
  CommerceFeeQuote quote(BigInt grossUnits) {
    if (grossUnits < BigInt.zero) {
      throw ArgumentError.value(
          grossUnits, 'grossUnits', 'must not be negative');
    }
    if (availability != CommerceAvailability.enabled) {
      throw StateError('Commerce fee schedule is not enabled');
    }

    if (grossUnits == BigInt.zero || basisPoints == 0) {
      return CommerceFeeQuote(
        lane: lane,
        scheduleVersion: version,
        grossUnits: grossUnits,
        feeUnits: BigInt.zero,
        netUnits: grossUnits,
      );
    }

    var feeUnits = grossUnits * BigInt.from(basisPoints) ~/ BigInt.from(10000);
    if (grossUnits > BigInt.zero && feeUnits < minimumFeeUnits) {
      feeUnits = minimumFeeUnits;
    }
    if (maximumFeeUnits != null && feeUnits > maximumFeeUnits!) {
      feeUnits = maximumFeeUnits!;
    }
    if (feeUnits > grossUnits) {
      throw StateError('Fee schedule would exceed the gross amount');
    }

    return CommerceFeeQuote(
      lane: lane,
      scheduleVersion: version,
      grossUnits: grossUnits,
      feeUnits: feeUnits,
      netUnits: grossUnits - feeUnits,
    );
  }
}

class CommerceFeeQuote {
  const CommerceFeeQuote({
    required this.lane,
    required this.scheduleVersion,
    required this.grossUnits,
    required this.feeUnits,
    required this.netUnits,
  });

  final CommerceLane lane;
  final int scheduleVersion;
  final BigInt grossUnits;
  final BigInt feeUnits;
  final BigInt netUnits;
}

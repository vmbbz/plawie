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
    this.settlementAsset,
    this.effectiveAt,
    this.expiresAt,
    this.recipientReference,
    this.disclosureText,
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
  final String? settlementAsset;
  final DateTime? effectiveAt;
  final DateTime? expiresAt;
  final String? recipientReference;
  final String? disclosureText;

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

  /// Builds the user-visible commission quote required by a future partner
  /// integration. Missing partner configuration fails closed.
  CommerceCommissionQuote quoteCommission({
    required BigInt grossAmountUnits,
    required BigInt partnerCostUnits,
    required DateTime quotedAt,
    required DateTime quoteExpiresAt,
  }) {
    final quotedAtUtc = quotedAt.toUtc();
    final expiryUtc = quoteExpiresAt.toUtc();
    if (effectiveAt != null && quotedAtUtc.isBefore(effectiveAt!.toUtc())) {
      throw StateError('Commerce fee schedule is not effective yet');
    }
    if (expiresAt != null && !quotedAtUtc.isBefore(expiresAt!.toUtc())) {
      throw StateError('Commerce fee schedule has expired');
    }
    if (!expiryUtc.isAfter(quotedAtUtc)) {
      throw ArgumentError('Commission quote expiry must be in the future.');
    }
    if (partnerCostUnits < BigInt.zero) {
      throw ArgumentError.value(
        partnerCostUnits,
        'partnerCostUnits',
        'cannot be negative',
      );
    }
    final asset = settlementAsset?.trim();
    final recipient = recipientReference?.trim();
    final disclosure = disclosureText?.trim();
    if (asset == null ||
        asset.isEmpty ||
        recipient == null ||
        recipient.isEmpty ||
        disclosure == null ||
        disclosure.isEmpty) {
      throw StateError('Commission schedule disclosure is incomplete');
    }

    final feeQuote = quote(grossAmountUnits);
    if (partnerCostUnits > feeQuote.netUnits) {
      throw StateError('Partner cost exceeds the amount available to settle');
    }
    return CommerceCommissionQuote(
      lane: lane,
      scheduleVersion: version,
      quotedAt: quotedAtUtc,
      expiresAt: expiryUtc,
      asset: asset,
      recipientReference: recipient,
      disclosureText: disclosure,
      grossAmountUnits: grossAmountUnits,
      partnerCostUnits: partnerCostUnits,
      platformFeeUnits: feeQuote.feeUnits,
      minimumReceivedUnits: feeQuote.netUnits - partnerCostUnits,
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

class CommerceCommissionQuote {
  const CommerceCommissionQuote({
    required this.lane,
    required this.scheduleVersion,
    required this.quotedAt,
    required this.expiresAt,
    required this.asset,
    required this.recipientReference,
    required this.disclosureText,
    required this.grossAmountUnits,
    required this.partnerCostUnits,
    required this.platformFeeUnits,
    required this.minimumReceivedUnits,
  });

  final CommerceLane lane;
  final int scheduleVersion;
  final DateTime quotedAt;
  final DateTime expiresAt;
  final String asset;
  final String recipientReference;
  final String disclosureText;
  final BigInt grossAmountUnits;
  final BigInt partnerCostUnits;
  final BigInt platformFeeUnits;
  final BigInt minimumReceivedUnits;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lane': lane.name,
        'scheduleVersion': scheduleVersion,
        'quotedAt': quotedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'asset': asset,
        'recipientReference': recipientReference,
        'disclosureText': disclosureText,
        'grossAmountUnits': grossAmountUnits.toString(),
        'partnerCostUnits': partnerCostUnits.toString(),
        'platformFeeUnits': platformFeeUnits.toString(),
        'minimumReceivedUnits': minimumReceivedUnits.toString(),
      };
}
